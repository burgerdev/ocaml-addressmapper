open Lwt

let response_of_opt = function
  | Some result -> Lwt.return @@ Server.Found result
  | None -> Lwt.return Server.Not_found

let handle_request rule =
  function
  | Server.Health -> Lwt.return Server.Healthy
  | Server.Put _ | Server.Other _ -> Lwt.return Server.Unsupported
  | Server.Get input ->
    return input >|= Mapper_rule.apply rule >>= response_of_opt

let string_of_response response = Fmt.strf "%a" Server.pp_response response

let handle rule _ (ic, oc) =
  Lwt_io.read_line ic
  >|= Server.request_of_string
  >>= handle_request rule
  >|= Fmt.strf "%a" Server.pp_response
  >>= Lwt_io.fprintl oc
  >>= fun _ -> Lwt_io.flush oc
