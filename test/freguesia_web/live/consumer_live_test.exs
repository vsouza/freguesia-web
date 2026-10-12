defmodule FreguesiaWeb.ConsumerLiveTest do
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Freguesia.Catalog.Place
  alias Freguesia.{Fixtures, Repo}
  alias Freguesia.Messaging.Fake

  describe "home do bairro (/bairro/:slug)" do
    test "lista os lugares verificados e não lista os pendentes", %{conn: conn} do
      neighborhood = Fixtures.neighborhood()
      verified = Fixtures.verified_place(%{name: "Pizzaria Visível", neighborhood: neighborhood})
      pending = Fixtures.verified_place(%{name: "Pizzaria Oculta", neighborhood: neighborhood})
      Repo.update_all(from_place(pending), set: [status: :pending])

      {:ok, view, _html} = live(conn, ~p"/bairro/savassi")

      assert has_element?(view, "#place-card-#{verified.slug}")
      refute render(view) =~ "Pizzaria Oculta"
    end

    test "mostra o selo Verificado e a etiqueta da oferta quando há oferta com resumo", %{
      conn: conn
    } do
      neighborhood = Fixtures.neighborhood()
      place = Fixtures.verified_place(%{name: "Com Selo", neighborhood: neighborhood})

      Repo.insert!(%Freguesia.Catalog.Offer{
        place_id: place.id,
        text: "10% no pedido direto",
        tag: "10% off",
        status: :approved,
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, view, _html} = live(conn, ~p"/bairro/savassi")

      assert has_element?(view, "#place-card-#{place.slug}", "Verificado")
      assert has_element?(view, "#place-card-#{place.slug}", "10% off")
      # O texto completo da oferta não vai ao card (regra 4)
      refute has_element?(view, "#place-card-#{place.slug}", "10% no pedido direto")
    end

    test "bairro sem lugares mostra o estado vazio", %{conn: conn} do
      Fixtures.neighborhood()
      {:ok, view, html} = live(conn, ~p"/bairro/savassi")

      assert html =~ "Chegam em breve"
      assert has_element?(view, "#places")
    end

    test "bairro inexistente cai na Savassi", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/bairro/savassi"}}} =
               live(conn, ~p"/bairro/nao-existe")
    end

    test "a inicial redireciona para o bairro padrão", %{conn: conn} do
      assert redirected_to(get(conn, ~p"/")) == "/bairro/savassi"
    end
  end

  describe "detalhes do lugar (/lugar/:slug)" do
    test "lugar verificado mostra o botão de WhatsApp com número e mensagem padrão", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Pizza do Lago", whatsapp_e164: "+5531977776666"})

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")

      assert has_element?(view, "#whatsapp-cta")
      html = view |> element("#whatsapp-cta") |> render()
      assert html =~ "https://wa.me/5531977776666?text="

      assert html =~
               URI.encode(
                 "Oi! Vi o Pizza do Lago na Freguesia e quero pedir direto.",
                 &URI.char_unreserved?/1
               )
    end

    test "lugar pausado mostra o estado e não oferece o botão de pedido", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Pausado"})

      Repo.update_all(from_place(place),
        set: [paused_until: DateTime.add(DateTime.utc_now(), 3600)]
      )

      {:ok, view, html} = live(conn, ~p"/lugar/#{place.slug}")
      assert html =~ "Sem atender hoje"
      refute has_element?(view, "a#whatsapp-cta")
    end

    test "lugar que não está no catálogo volta para o bairro", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Pendente Escondido"})
      Repo.update_all(from_place(place), set: [status: :pending])

      assert {:error, {:live_redirect, %{to: "/bairro/savassi"}}} =
               live(conn, ~p"/lugar/#{place.slug}")
    end
  end

  describe "cadastro em 3 passos (/cadastrar)" do
    test "fluxo completo: dados, código no WhatsApp, confirmação e tela de sucesso", %{conn: conn} do
      segment = Fixtures.restaurants()
      Fixtures.category()
      Fixtures.neighborhood()

      {:ok, view, html} = live(conn, ~p"/cadastrar")
      assert html =~ "Passo 1 de 3"

      # Tipo restaurante mostra o campo de tipo de comida
      refute has_element?(view, "#signup-form select[name='signup[category_id]']")

      view
      |> element("#signup-form")
      |> render_change(%{"signup" => %{"segment_id" => segment.id}})

      assert has_element?(view, "#signup-form select[name='signup[category_id]']")

      params =
        Fixtures.signup_params(%{"whatsapp" => "(31) 97777-1234", "name" => "Cantina da Esquina"})

      view |> form("#signup-form", signup: params) |> render_submit()

      assert has_element?(view, "#code-form")
      assert render(view) =~ "1234"

      [message] = Fake.sent_to("+5531977771234")
      code = message.params["code"]

      view |> form("#code-form", code: %{code: "000000"}) |> render_submit()
      assert render(view) =~ "Código incorreto"

      view |> form("#code-form", code: %{code: code}) |> render_submit()

      assert has_element?(view, "#signup-done")
      assert render(view) =~ "Em análise, até 1 dia útil"
    end

    test "erros de validação aparecem no formulário", %{conn: conn} do
      segment = Fixtures.restaurants()
      Fixtures.category()
      Fixtures.neighborhood()
      {:ok, view, _html} = live(conn, ~p"/cadastrar")

      # Como no uso real: escolhe o tipo antes, para o campo de comida aparecer
      view
      |> element("#signup-form")
      |> render_change(%{"signup" => %{"segment_id" => segment.id}})

      view
      |> form("#signup-form",
        signup: Fixtures.signup_params(%{"whatsapp" => "123", "name" => "ab"})
      )
      |> render_submit()

      assert has_element?(view, "#signup-form", "use um WhatsApp brasileiro com DDD")
      assert has_element?(view, "#signup-form", "use entre 3 e 60 caracteres")
    end
  end

  defp from_place(place) do
    import Ecto.Query
    from(p in Place, where: p.id == ^place.id)
  end
end
