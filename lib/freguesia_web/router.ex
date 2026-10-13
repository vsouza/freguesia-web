defmodule FreguesiaWeb.Router do
  use FreguesiaWeb, :router

  import FreguesiaWeb.AdminAuth, only: [fetch_current_operator: 2, require_operator: 2]

  # PRD §13: own scripts and Google Fonts (AdSense comes in phase 2).
  # LiveView uses inline styles in its JS commands, hence 'unsafe-inline' in style-src.
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
    plug FreguesiaWeb.Locale
    plug FreguesiaWeb.DeviceSession
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

  # Liveness probe for deploys: no session, no CSRF.
  scope "/", FreguesiaWeb do
    get "/health", HealthController, :index
    get "/photos/:key", PhotoController, :show
  end

  scope "/", FreguesiaWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/start", OnboardingController, :start
    get "/terms", LegalController, :terms
    get "/privacy", LegalController, :privacy
    get "/how-we-calculate", LegalController, :how_we_calculate
    get "/location/:neighborhood", LocationController, :set
    get "/places/:slug/whatsapp", WhatsAppController, :open

    live_session :catalog, on_mount: [FreguesiaWeb.Locale] do
      live "/location", LocationLive
      live "/areas/:neighborhood", NeighborhoodLive
      live "/search", SearchLive
      live "/business/register", SignupLive
    end
  end

  # The place page carries Open Graph tags, set before the LiveView renders (PRD §5).
  scope "/", FreguesiaWeb do
    pipe_through [:browser, FreguesiaWeb.PlaceMeta]

    live_session :place, on_mount: [FreguesiaWeb.Locale] do
      live "/places/:slug", PlaceLive
    end
  end

  scope "/admin", FreguesiaWeb.Admin do
    pipe_through [:browser, :admin]

    get "/", SessionController, :index
    get "/sign-in", SessionController, :new
    post "/sign-in", SessionController, :create
    get "/sign-in/code", SessionController, :totp
    post "/sign-in/code", SessionController, :verify_totp
    get "/sign-in/2fa-setup", SessionController, :enroll
    post "/sign-in/2fa-setup", SessionController, :confirm_enroll
    delete "/sign-out", SessionController, :delete
  end

  scope "/admin", FreguesiaWeb.Admin do
    pipe_through [:browser, :admin, :admin_authenticated]

    live_session :admin,
      on_mount: [FreguesiaWeb.Locale, {FreguesiaWeb.AdminAuth, :require_operator}] do
      live "/verifications", VerificationsLive
      live "/verifications/:id", VerificationLive
      live "/places", PlacesLive
      live "/places/:id", PlaceLive
      live "/complaints", ComplaintsLive
      # Fake inbox: where the verification code shows up in dev and staging.
      # Behind login, because in staging it shows real test codes.
      live "/fake-inbox", FakeInboxLive
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
