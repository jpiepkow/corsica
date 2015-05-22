defmodule Corsica.Router do
  @moduledoc """
  A router to handle and respond to CORS requests.

  This module provides facilities for creating
  [`Plug.Router`](https://hexdocs.pm/plug/Plug.Router.html)-based routers that
  handle CORS requests. A generated router will handle a CORS request by:

    * responding to it if it's a preflight request (refer to
      `Corsica.send_preflight_resp/4` for more information) or
    * adding the right CORS headers to the connection if it's a valid CORS
      request.

  ## Examples

      defmodule MyApp.CORS do
        use Corsica.Router

        @opts [
          origins: ["http://foo.com", "http://bar.com"],
          allow_credentials: true,
          max_age: 600,
        ]

        resource "/public/*", Keyword.merge(@opts, origins: "*")
        resource "/*", @opts
      end

  Now in your application's endpoint:

      defmodule MyApp.Endpoint do
        plug Plug.Head
        plug MyApp.CORS
        plug MyApp.Router
      end

  """

  @doc false
  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__), only: [resource: 2]

      @corsica_router_opts unquote(opts)

      use Plug.Router
      plug :match
      plug :dispatch
    end
  end

  @doc """
  Defines a CORS-enabled resource.

  This macro takes advantage of the macros defined by
  [`Plug.Router`](https://hexdocs.pm/plug/Plug.Router.html) (like `options/3`
  and `match/3`) in order to define regular `Plug.Router`-like routes that
  efficiently match on the request url; the bodies of the autogenerated routes
  just perform a couple of checks before calling either
  `Corsica.put_cors_simple_resp_headers/2` or `Corsica.send_preflight_resp/4`.

  Note that if the request is a CORS preflight request (whether it's a valid one
  or not), a response is immediately sent to the client (whether the request is
  a valid one or not). This behaviour, combined with the definition of an
  additional `OPTIONS` route to `route`, makes `Corsica.Router` ideal to just
  put before any router in a plug pipeline, letting it handle preflight requests
  by itself.

  The options given to `resource/2` are merged with the default options like it
  happens with the rest of the functions in the `Corsica` module.

  ## Examples

      resources "/foo", origins: "*"
      resources "/wildcards/are/ok/*", max_age: 600

  """
  defmacro resource(route, opts \\ []) do
    quote do
      route = unquote(route)

      # Plug.Router wants this.
      if String.ends_with?(route, "*") do
        route = route <> "_"
      end

      options route do
        conn = var!(conn)
        if Corsica.preflight_req?(conn) do
          Corsica.send_preflight_resp(conn, unquote(opts))
        else
          conn
        end
      end

      match route do
        conn = var!(conn)
        if Corsica.cors_req?(conn) do
          Corsica.put_cors_simple_resp_headers(conn, unquote(opts))
        else
          conn
        end
      end
    end
  end
end