import gleam/int
import gleam/list
import gleam/string
import gleam/string_tree
import simplifile
import wisp.{type Request, type Response}

pub fn handle_request(request: Request) -> Response {
  use <- wisp.log_request(request)
  use <- wisp.serve_static(request, under: "/", from: "public/")

  case wisp.path_segments(request) {
    // `/` - returns homepage
    [] -> home_page()

    // `/cats` - returns a list of all cat IDs
    ["cats"] -> cats()

    // `/cat/random` - returns a random cat ID
    ["cats", "random"] -> random_cat(request)

    // `/cat/:id` - returns a cat image of the given ID
    ["cats", id] -> show_cat(id)

    _ -> random_cat(request)
  }
}

fn home_page() -> Response {
  wisp.redirect("/index.html")
}

fn get_cat_files() -> List(String) {
  case simplifile.get_files("public/cats") {
    Ok(files) -> {
      list.filter(files, fn(f) {
        string.ends_with(f, ".png") || string.ends_with(f, ".jpg")
      })
    }
    Error(_) -> []
  }
}

fn get_cat_count() -> Int {
  list.length(get_cat_files())
}

fn get_cat_ids() -> List(String) {
  get_cat_files()
  |> list.map(fn(filename) {
    case string.split(filename, ".") {
      [id, _] -> id
      _ -> ""
    }
  })
  |> list.filter(fn(id) { id != "" })
}

fn cats() -> Response {
  let cat_ids = get_cat_ids()
  let cat_list =
    list.map(cat_ids, fn(id) {
      "{\"id\": \"" <> id <> "\", \"url\": \"/cats/" <> id <> ".png\"}"
    })

  let json_body = "{\"cats\": [" <> string.join(cat_list, ", ") <> "]}"

  wisp.ok()
  |> wisp.json_body(string_tree.from_string(json_body))
}

fn show_cat(id: String) -> Response {
  let image_url = "/cats/" <> id <> ".png"
  let html = "<img src=\"" <> image_url <> "\" alt=\"Cat #" <> id <> "\">"

  wisp.ok()
  |> wisp.set_header("content-type", "text/html")
  |> wisp.html_body(string_tree.from_string(html))
}

fn random_cat(request: Request) -> Response {
  let cat_count = get_cat_count()

  case cat_count {
    0 -> {
      wisp.not_found()
      |> wisp.json_body(string_tree.from_string(
        "{\"error\": \"No cat images found\"}",
      ))
    }

    _ -> {
      let random_id = int.to_string(int.random(cat_count) + 1)
      let image_url = "/cats/" <> random_id <> ".png"

      let query = wisp.get_query(request)
      let wants_json =
        list.any(query, fn(pair) {
          let #(key, _) = pair
          key == "json"
        })

      case wants_json {
        True -> {
          wisp.ok()
          |> wisp.set_header("content-type", "application/json")
          |> wisp.json_body(string_tree.from_string(
            "{\"id\": \""
            <> random_id
            <> "\", \"url\": \""
            <> image_url
            <> "\"}",
          ))
        }
        False -> {
          let html = "<img src=\"" <> image_url <> "\" alt=\"Random Cat\">"

          wisp.ok()
          |> wisp.set_header("content-type", "text/html")
          |> wisp.html_body(string_tree.from_string(html))
        }
      }
    }
  }
}
