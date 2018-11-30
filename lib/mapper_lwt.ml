open Lwt

let percent_encoding_re = Str.regexp "%\\([0-9a-fA-F][0-9a-fA-F]\\)"

let percent_decode =
  Str.global_substitute percent_encoding_re @@ fun x ->
  Str.replace_matched "0x\\1" x
  |> int_of_string
  |> char_of_int
  |> String.make 1

let percent_encode s =
  begin
    let ppf = Format.str_formatter in
    s |> String.iter @@
    function
    | '\x21' .. '\x7e' as c ->
      Format.fprintf ppf "%c" c
    | c ->
      int_of_char c
      |> Format.fprintf ppf "%%%02X"
  end;
  Format.flush_str_formatter ()

module Request = struct
  open MParser

  type request =
    | Get of string
    | Put of string
    | Health
    | Other of string

  let get = string "get" <|> string "GET"
  let put = string "put" <|> string "PUT"
  let health = string "health" <|> string "HEALTH"

  let get_req = get >> spaces >> many_chars any_char
                |>> percent_decode
                |>> fun s -> Get s

  let put_req = put >> spaces >> many_chars any_char
                |>> percent_decode
                |>> fun s -> Put s

  let health_req = health >>$ Health

  let other_req = many any_char |>> List.to_seq |>> String.of_seq |>> fun s -> Other s

  let request_parser = get_req <|> put_req <|> health_req <|> other_req


  let request_of_string line =
    match parse_string request_parser line () with
    | Success req -> req
    | Failed (x, _) -> Other x

  let pp_request = Fmt.hbox @@ Fmt.of_to_string @@ function
    | Get s -> "get " ^ s
    | Put s -> "put " ^ s
    | Health -> "health"
    | Other s -> s
end

module Response = struct

  type response =
    | Malformed
    | Not_found
    | Internal_error
    | Unsupported
    | Found of string
    | Healthy
    | Unhealthy

  let code_of_response = function
    | Found _ | Healthy -> 200
    | Internal_error | Unhealthy -> 400
    | Malformed | Not_found | Unsupported -> 500

  let pp_response_code = Fmt.using code_of_response Fmt.int

  let msg_of_response = function
    | Malformed -> "malformed request"
    | Not_found -> "not found"
    | Internal_error -> "internal server error"
    | Unsupported -> "not implemented"
    | Found s -> percent_encode s
    | Healthy -> "ok"
    | Unhealthy -> "not ok"

  let pp_response_msg = Fmt.of_to_string msg_of_response

  let pp =
    Fmt.using (fun x -> (x, x))
    @@ Fmt.pair ~sep:Fmt.sp pp_response_code pp_response_msg
    |> Fmt.hbox

  let of_opt = function
    | Some result -> Lwt.return @@ Found result
    | None -> Lwt.return Not_found

end

let handle_request rule =
  function
  | Request.Health -> Lwt.return Response.Healthy
  | Request.Put _ | Request.Other _ -> Lwt.return Response.Unsupported
  | Request.Get input ->
    return input >|= Mapper_rule.apply rule >>= Response.of_opt

let handle rule _ (ic, oc) =
  Lwt_io.read_line ic
  >|= Request.request_of_string
  >>= handle_request rule
  >|= Fmt.strf "%a" Response.pp
  >>= Lwt_io.fprintl oc
  >>= fun _ -> Lwt_io.flush oc
