import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Plaid requires Link to be loaded from its CDN, not bundled.
const PLAID_LINK_SCRIPT = "https://cdn.plaid.com/link/v2/stable/link-initialize.js"
let plaidLinkLoaded

function loadPlaidLink() {
  plaidLinkLoaded ??= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = PLAID_LINK_SCRIPT
    script.onload = resolve
    script.onerror = () => {
      plaidLinkLoaded = undefined
      reject(new Error("Couldn't load Plaid. Check your connection and try again."))
    }
    document.head.append(script)
  })
  return plaidLinkLoaded
}

// Connects an account: gets a link token for the chosen kind of account, opens
// Plaid Link, and sends the public token from a successful link to the server.
export default class extends Controller {
  static targets = ["button", "error"]
  static values = { from: String }

  async open({ params: { kind } }) {
    this.#setBusy(true)
    this.#showError(null)

    try {
      await loadPlaidLink()
      const { link_token } = await this.#post("/plaid/link_tokens", { kind })

      window.Plaid.create({
        token: link_token,
        onSuccess: (publicToken) => this.#connect(publicToken),
        onExit: (error) => {
          this.#setBusy(false)
          if (error) this.#showError("The connection didn't finish. Please try again.")
        }
      }).open()
    } catch (error) {
      this.#setBusy(false)
      this.#showError(error.message)
    }
  }

  async #connect(publicToken) {
    try {
      const { redirect_url } = await this.#post("/plaid_items", { public_token: publicToken, from: this.fromValue })
      Turbo.visit(redirect_url)
    } catch (error) {
      this.#setBusy(false)
      this.#showError(error.message)
    }
  }

  async #post(url, body) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: JSON.stringify(body)
    })
    const json = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(json.error || "Something went wrong. Please try again.")
    return json
  }

  #setBusy(busy) {
    this.buttonTargets.forEach((button) => {
      button.disabled = busy
      button.setAttribute("aria-busy", busy)
    })
  }

  #showError(message) {
    this.errorTarget.textContent = message ?? ""
    this.errorTarget.hidden = !message
  }
}
