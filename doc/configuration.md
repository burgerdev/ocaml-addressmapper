# AddressMapper Configuration

The AddressMapper works with configuration files consisting of
[S-expressions](https://en.wikipedia.org/wiki/S-expression). Those are basically
nested, parenthesized rules how the input query should be handled. Below is an
EBNF grammar that provides an overview over the possible rules.

## Configuration File Syntax

```EBNF
rule                  = terminal-rule | combined-rule;
terminal-rule         = action-symbol | transformation-rule;

(* These rules are leafs with predefined behaviour. *)
action-symbol         = 'accept' | 'reject' | 'lower' | 'upper';

(* These clauses transform a string according to specific rules. *)
transformation-rule   = '(', matches-rule | replace-rule | constant-rule, ')';
matches-rule          = 'matches', white-space, regexp-literal;
replace-clause        = 'replace', white-space, regexp-literal, white-space, string-literal;
constant-rule         = 'constant', white-space, string-literal;
equals-rule           = 'equals', white-space, string-literal;
prefix-rule           = 'prefix_matches', white-space, string-literal;
suffix-rule           = 'suffix_matches', white-space, string-literal;

(* These rules consist of further, nested rules. *)
combined-rule         = rule-list | first-rule | boolean-rule;
rule-list             = '(', { rule { white-space, rule } }, ')';
first-rule            = '(', 'first', white-space, rule-list, ')';
boolean-rule          = '(', and-rule | or-rule | not-rule, ')';
and-rule              = rule, white-space, '&&', white-space, rule;
or-rule               = rule, white-space, '||', white-space, rule;
not-rule              = 'not', white-space, rule;

(* handwavingly declared symbols *)
regexp-literal        = ? double quoted regular expression ?;
string-literal        = ? double quoted literal string ?;
white-space           = ? one or more characters like ' ', '\t', '\n' ?;
```

## Configuration File Semantics

### Traversal

After a query has arrived, the sexp-tree is traversed depth-first, applying each
of the encountered rules to the input and passing the output on to the next
rule. A rule `r` is said to be *fulfilled for an input string `q`*, if it
transforms `q` to an output string `q' = r(q)`. On the other hand, a rule is
said to be *not fulfilled for an input string `q`* if `r(q) = None`.

Suppose we have input `q` arriving at an `'all'` rule: `r: ('all' a b c)`.
The output will then be `r(q) := c(b(a(q)))` if all rules can be fulfilled by
their respective input. If e.g. `b(a(q))` can't be fulfilled, the result of rule
`r` will be `None`.

After all rules have been evaluated, the final output determines the query
result. If it's a string, the result will be `200 <final-output>`, if it's
`None`, the result will be `500 not-found`.

### Actions

  - `accept`:
    This rule is always fulfilled. It passes the input on unmodified.
  - `reject`:
    This rule is never fulfilled. It always returns `None`.
  - `lower`:
    This rule is always fulfilled. It converts all upper space characters to
    lower space characters.
  - `upper`:
    This rule is always fulfilled. It converts all lower space characters to
    upper space characters.

### Transformations

  - `matches <regex>`:
    If the input string matches the given regular expression, it is passed on
    unchanged. If the string does not match, `None` is returned.
  - `replace <regex> <literal>`:
    The input is searched for the first match of the given regular expression,
    which is then replaced by the given string literal. If no match is found,
    the input is passed on unchanged.
  - `constant <literal>`:
    The input is replaced with the given string literal.
  - `equals <literal>`:
    The input is accepted iff it is exactly equal to the given string literal.
  - `prefix_matches <literal>`:
    The input is accepted iff it starts with the given string literal.
  - `suffix_matches <literal>`:
    The input is accepted iff it ends with the given string literal.

### Combinations

  - `[all] (<rule1> .. <ruleN>)`:
    This rule maps the input string through all child rules, until either `None`
    is returned by a rule or all rules have been fulfilled. In the former case,
    the result of `all` is `None`. In the latter case, it will be the result of
    the final `<ruleN>`. The `all` keyword is optional, but can be added to
    make the rule more clear. An empty list is equivalent to `accept`.
    **Bonus**: `all (<rule1> <rule2>)` can be written as `<rule1> && <rule2>`.
  - `first (<rule1> .. <ruleN>)`:
    This rule maps the input string through all child rules, until either a rule
    can be fulfilled, or until all rules have returned `None`. In the former
    case, `first` will have the result of the first rule that could be
    fulfilled. In the latter case, `None` will be returned. An empty list is
    equivalent to `reject`.
    **Bonus**: `first (<rule1> <rule2>)` can be written as `<rule1> || <rule2>`.
  - `not <rule>`:
    This rule returns `None` if the argument rule was fulfilled, otherwise it
    returns the input string.
