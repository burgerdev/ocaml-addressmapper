(all
 (first
  (matches "^ab")
  (matches "yz$")
  reject
 )
 (replace "a" "b")
 accept
 (replace "[0-9]+" "NUMBERS")
)
