defmodule FreguesiaWeb.Router do
  use FreguesiaWeb, :router

  import FreguesiaWeb.AdminAuth, only: [fetch_current_operator: 2, require_operator: 2]

  # PRD §13: scripts próprios, Google Fonts (AdSense entra na fase 2).
  # LiveView usa estilo inline nos comandos JS, por isso 'unsafe-inline' em style-src.
  @content_security_policy Enum.join(
                             [
                               "default-src 'self'",
                               "script-src 'self'",
                               "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
                               "font-src 'self' https://fonts.gstatic.com",
                               "img-src 'self' data:",
                               "connect-src 'self' ws: wss:",
                               "frame-ancestors 'none'",
                               "base-uri 'self'",
                               "form-action 'self'"
                             ],
                             "; "
                           )

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FreguesiaWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" => @content_security_policy,
      "referrer-policy" => "strict-origin-when-cross-origin"
    }
  end

  pipeline :admin do
    plug :fetch_current_operator
  end

  pipeline :admin_authenticated do
    plug :require_operator
  end

  # Liveness para o deploy: sem sessão, sem CSRF.
  scope "/", FreguesiaWeb do
    get "/health", HealthController, :index
  end

  scope "/", FreguesiaWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :catalog do
      live "/bairro/:slug", NeighborhoodLive
      live "/lugar/:slug", PlaceLive
      live "/cadastrar", SignupLive
    end
  end

  scope "/admin", FreguesiaWeb.Admin do
    pipe_through [:browser, :admin]

    get "/", SessionController, :index
    get "/entrar", SessionController, :new
    post "/entrar", SessionController, :create
    get "/entrar/codigo", SessionController, :totp
    post "/entrar/codigo", SessionController, :verify_totp
    get "/entrar/cadastrar-2fa", SessionController, :enroll
    post "/entrar/cadastrar-2fa", SessionController, :confirm_enroll
    delete "/sair", SessionController, :delete
  end

  scope "/admin", FreguesiaWeb.Admin do
    pipe_through [:browser, :admin, :admin_authenticated]

    live_session :admin,
      on_mount: [{FreguesiaWeb.AdminAuth, :require_operator}] do
      live "/verificacoes", VerificationsLive
      live "/verificacoes/:id", VerificationLive
      # Caixa do Fake: é onde o código de verificação aparece em dev e em staging.
      # Fica atrás do login, porque em staging ela mostra códigos reais de teste.
      live "/mensagens-fake", FakeInboxLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:freguesia, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FreguesiaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
