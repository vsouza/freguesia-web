defmodule FreguesiaWeb.LegalAndPwaTest do
  use FreguesiaWeb.ConnCase, async: true

  describe "legal pages" do
    test "terms, privacy and how we calculate are published and marked as drafts", %{conn: conn} do
      for path <- [~p"/terms", ~p"/privacy", ~p"/how-we-calculate"] do
        html = conn |> get(path) |> html_response(200)
        assert html =~ "RASCUNHO"
        assert html =~ "Versão"
      end
    end

    test "the footer links to the legal pages", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)
      assert html =~ ~s(href="/terms")
      assert html =~ ~s(href="/privacy")
      assert html =~ ~s(href="/how-we-calculate")
    end
  end

  describe "PWA" do
    test "the manifest declares standalone display and a 512 icon" do
      manifest =
        Jason.decode!(File.read!(Path.join(:code.priv_dir(:freguesia), "static/manifest.json")))

      assert manifest["display"] == "standalone"
      assert Enum.any?(manifest["icons"], &(&1["sizes"] == "512x512"))
    end

    test "the service worker serves the offline page", %{} do
      sw = File.read!(Path.join(:code.priv_dir(:freguesia), "static/sw.js"))
      assert sw =~ "offline.html"
      assert File.exists?(Path.join(:code.priv_dir(:freguesia), "static/offline.html"))
    end

    test "the root layout links the manifest", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)
      assert html =~ ~s(rel="manifest")
    end
  end
end
