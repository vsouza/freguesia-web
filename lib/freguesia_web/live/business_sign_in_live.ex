defmodule FreguesiaWeb.BusinessSignInLive do
  @moduledoc """
  Business sign-in (PRD §6): Google, Apple and e-mail with password through Firebase
  Authentication, in the browser (`assets/js/firebase_sign_in.js`). The ID token goes to
  `POST /business/session`, which verifies it on the server.

  Until the Firebase web config is set (`FIREBASE_*` variables), the provider buttons stay
  disabled. In dev and test the e-mail form signs in with the Fake identity instead.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Business

  @impl true
  def mount(_params, _session, socket) do
    firebase = Business.firebase_web_config()

    {:ok,
     socket
     |> assign(
       page_title: gettext("Business sign-in"),
       firebase_config: firebase,
       firebase_json: firebase && Jason.encode!(firebase),
       email_form: to_form(%{"email" => "", "password" => ""}, as: :firebase),
       dev_sign_in?: Business.dev_identity?(),
       dev_form: to_form(%{"email" => ""})
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_neighborhood={@current_neighborhood}>
      <FreguesiaWeb.Components.two_line_title
        first={gettext("Your place,")}
        second={gettext("your account.")}
      />

      <p class="mt-4 text-sm text-ink-2">
        {gettext(
          "With an account you register your place, set where it delivers, and keep its perks and hours up to date. Customers don't need one."
        )}
      </p>

      <div
        id="firebase-sign-in"
        phx-hook="FirebaseSignIn"
        phx-update="ignore"
        data-config={@firebase_json}
        data-msg-failed={gettext("We could not confirm your sign-in. Try again.")}
        data-msg-email={gettext("Enter your e-mail and password.")}
        class="mt-6 flex flex-col gap-3"
      >
        <button
          type="button"
          id="sign-in-google"
          data-provider="google"
          disabled={@firebase_config == nil}
          class="flex min-h-12 items-center justify-center gap-2 rounded-full border border-line bg-white px-5 font-bold text-ink hover:bg-sand disabled:opacity-50"
        >
          {gettext("Continue with Google")}
        </button>
        <button
          type="button"
          id="sign-in-apple"
          data-provider="apple"
          disabled={@firebase_config == nil}
          class="flex min-h-12 items-center justify-center gap-2 rounded-full border border-line bg-white px-5 font-bold text-ink hover:bg-sand disabled:opacity-50"
        >
          {gettext("Continue with Apple")}
        </button>

        <.form
          for={@email_form}
          id="firebase-email-form"
          class="mt-2 flex flex-col gap-2 rounded-card bg-sand p-5"
        >
          <.input
            field={@email_form[:email]}
            id="firebase-email"
            type="email"
            label={gettext("E-mail")}
            autocomplete="username"
            disabled={@firebase_config == nil}
            class="h-12 rounded-full border border-line bg-white px-5 text-base disabled:opacity-50"
          />
          <.input
            field={@email_form[:password]}
            id="firebase-password"
            type="password"
            label={gettext("Password")}
            autocomplete="current-password"
            disabled={@firebase_config == nil}
            class="h-12 rounded-full border border-line bg-white px-5 text-base disabled:opacity-50"
          />
          <div class="mt-1 grid grid-cols-2 gap-2">
            <button
              type="button"
              id="email-sign-in"
              data-email-action="sign-in"
              disabled={@firebase_config == nil}
              class="min-h-12 rounded-full bg-ink font-bold text-white disabled:opacity-50"
            >
              {gettext("Sign in")}
            </button>
            <button
              type="button"
              id="email-create"
              data-email-action="create"
              disabled={@firebase_config == nil}
              class="min-h-12 rounded-full border border-line bg-white font-bold text-ink disabled:opacity-50"
            >
              {gettext("Create account")}
            </button>
          </div>
        </.form>

        <p id="firebase-error" role="alert" class="text-sm font-bold text-tomato-600" hidden></p>
      </div>

      <p :if={@firebase_config == nil} id="sign-in-unavailable" class="mt-3 text-xs text-muted">
        {gettext("Google, Apple and e-mail sign-in are not enabled in this environment yet.")}
      </p>

      <.form
        :if={@dev_sign_in?}
        for={@dev_form}
        id="dev-sign-in-form"
        action={~p"/business/session"}
        method="post"
        class="mt-8 flex flex-col gap-3 rounded-card border border-dashed border-line p-5"
      >
        <p class="text-xs font-bold uppercase tracking-wide text-muted">
          {gettext("Development sign-in")}
        </p>
        <.input
          field={@dev_form[:email]}
          id="dev-sign-in-email"
          type="email"
          label={gettext("E-mail")}
          required
          placeholder="voce@exemplo.com"
          class="h-12 rounded-full border border-line bg-white px-5 text-base"
        />
        <button
          type="submit"
          id="dev-sign-in-submit"
          class="min-h-12 rounded-full bg-ink font-bold text-white"
        >
          {gettext("Sign in")}
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
