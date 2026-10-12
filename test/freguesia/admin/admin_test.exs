defmodule Freguesia.AdminTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Admin, Fixtures, Repo}
  alias Freguesia.Admin.AuditEntry

  describe "senha" do
    test "create_operator grava hash, nunca a senha" do
      operator = Fixtures.operator()
      assert operator.password_hash =~ "$argon2id$"
      refute operator.password
    end

    test "senha curta é recusada" do
      assert {:error, changeset} =
               Admin.create_operator(%{email: "x@freguesia.test", password: "curta"})

      assert changeset.errors[:password]
    end

    test "authenticate aceita a senha certa e recusa a errada e e-mail desconhecido" do
      operator = Fixtures.operator(%{email: "ana@freguesia.test"})

      assert {:ok, found} = Admin.authenticate("ANA@freguesia.test ", Fixtures.password())
      assert found.id == operator.id

      assert {:error, :invalid} = Admin.authenticate("ana@freguesia.test", "errada-errada-errada")

      assert {:error, :invalid} =
               Admin.authenticate("ninguem@freguesia.test", "qualquer-coisa-aqui")
    end
  end

  describe "2FA (TOTP)" do
    test "enrolamento: o código certo confirma e depois é exigido" do
      operator = Fixtures.operator()

      assert {:ok, operator, uri} = Admin.start_totp_enrollment(operator)
      assert uri =~ "otpauth://totp/"
      assert operator.totp_confirmed_at == nil

      code = NimbleTOTP.verification_code(operator.totp_secret)
      assert {:ok, confirmed} = Admin.confirm_totp_enrollment(operator, code)
      assert confirmed.totp_confirmed_at

      assert {:ok, _} =
               Admin.verify_totp(confirmed, NimbleTOTP.verification_code(confirmed.totp_secret))

      assert {:error, :invalid_code} = Admin.verify_totp(confirmed, "000000x")
    end

    test "recarregar o enrolamento não troca o segredo" do
      operator = Fixtures.operator()
      {:ok, first, _} = Admin.start_totp_enrollment(operator)
      {:ok, second, _} = Admin.start_totp_enrollment(first)

      assert first.totp_secret == second.totp_secret
    end

    test "código de enrolamento errado não confirma" do
      {:ok, operator, _} = Admin.start_totp_enrollment(Fixtures.operator())
      assert {:error, :invalid_code} = Admin.confirm_totp_enrollment(operator, "123456x")
    end

    test "operador sem 2FA confirmado não passa na verificação" do
      {:ok, operator, _} = Admin.start_totp_enrollment(Fixtures.operator())
      assert {:error, :not_enrolled} = Admin.verify_totp(operator, "123456")
    end
  end

  describe "sessão" do
    test "sessão dentro de 8 horas devolve o operador" do
      operator = Fixtures.operator()
      session = %{"operator_id" => operator.id, "operator_at" => System.system_time(:second)}

      assert Admin.fetch_session_operator(session).id == operator.id
    end

    test "sessão mais antiga que 8 horas expira" do
      operator = Fixtures.operator()
      old = System.system_time(:second) - Admin.session_ttl_seconds() - 1
      session = %{"operator_id" => operator.id, "operator_at" => old}

      assert Admin.fetch_session_operator(session) == nil
    end

    test "sem sessão não há operador" do
      assert Admin.fetch_session_operator(%{}) == nil
    end
  end

  describe "audit_log" do
    test "record_audit grava a linha" do
      operator = Fixtures.operator()

      assert {:ok, entry} =
               Admin.record_audit(operator, "teste.acao", "place", "abc", %{"a" => 1}, %{"a" => 2})

      assert entry.admin_id == operator.id
      assert [_] = Admin.audit_entries("place", "abc")
    end

    test "o banco não deixa alterar nem apagar uma linha do audit_log" do
      {:ok, _entry} = Admin.record_audit(nil, "teste.imutavel", "place", "x", nil, nil)

      assert_raise Postgrex.Error, ~r/audit_log é imutável/, fn ->
        Repo.update_all(AuditEntry, set: [action: "adulterado"])
      end
    end
  end
end
