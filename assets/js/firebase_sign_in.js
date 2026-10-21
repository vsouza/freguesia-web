// Browser side of business sign-in (PRD §6).
//
// Firebase proves who the person is (Google, Apple or e-mail and password). The browser
// then posts the ID token to our server, which verifies it and opens its own session.
// Later requests never call Firebase again.
//
// Registered in app.js as the "FirebaseSignIn" hook. The hook element carries the public
// web config as JSON in `data-config`; without it the buttons stay disabled.
import {getApps, initializeApp} from "firebase/app"
import {
  createUserWithEmailAndPassword,
  getAuth,
  GoogleAuthProvider,
  OAuthProvider,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth"

const APP_NAME = "freguesia-business"

export const FirebaseSignIn = {
  mounted() {
    const config = JSON.parse(this.el.dataset.config || "null")
    this.failedMessage = this.el.dataset.msgFailed
    this.emailMessage = this.el.dataset.msgEmail
    this.error = this.el.querySelector("#firebase-error")
    if (!config) return

    const app = getApps().find(existing => existing.name === APP_NAME) || initializeApp(config, APP_NAME)
    this.auth = getAuth(app)

    // Enter in the e-mail form signs in; it must not submit the page.
    this.el.addEventListener("submit", event => {
      event.preventDefault()
      this.signInWithEmail("sign-in")
    })

    this.el.addEventListener("click", event => {
      const button = event.target.closest("[data-provider], [data-email-action]")
      if (!button) return
      event.preventDefault()

      if (button.dataset.provider) {
        this.signInWithProvider(button.dataset.provider)
      } else {
        this.signInWithEmail(button.dataset.emailAction)
      }
    })
  },

  signInWithProvider(name) {
    const provider = name === "apple" ? new OAuthProvider("apple.com") : new GoogleAuthProvider()
    this.finish(() => signInWithPopup(this.auth, provider))
  },

  signInWithEmail(action) {
    const email = this.el.querySelector("#firebase-email").value.trim()
    const password = this.el.querySelector("#firebase-password").value
    if (!email || !password) return this.fail(this.emailMessage)

    const run = action === "create" ? createUserWithEmailAndPassword : signInWithEmailAndPassword
    this.finish(() => run(this.auth, email, password))
  },

  async finish(signIn) {
    try {
      const credential = await signIn()
      const token = await credential.user.getIdToken()
      this.post(token)
    } catch (_error) {
      this.fail(this.failedMessage)
    }
  },

  fail(message) {
    this.error.textContent = message
    this.error.hidden = false
  },

  // A plain form post sets the session cookie through the server's redirect.
  post(token) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = "/business/session"
    form.hidden = true

    const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content")
    for (const [name, value] of [["_csrf_token", csrf], ["id_token", token]]) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    }

    document.body.appendChild(form)
    form.submit()
  },
}
