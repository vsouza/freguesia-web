defmodule Freguesia.AdminTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Admin, Fixtures, Repo}
  alias Freguesia.Admin.AuditEntry

  describe "password" do
    test "create_operator stores a hash, never the password" do
      operator = Fixtures.operator()
      assert operator.password_hash =~ "$argon2id$"
      refute operator.password
    end

    test "short password is rejected" do
      assert {:error, changeset} =
               Admin.create_operator(%{email: "x@freguesia.test", password: "curta"})

      assert changeset.errors[:password]
    end

    test "authenticate accepts the right password and rejects a wrong one and unknown emails" do
      operator = Fixtures.operator(%{email: "ana@freguesia.test"})

      assert {:ok, found} = Admin.authenticate("ANA@freguesia.test ", Fixtures.password())
      assert found.id == operator.id

      assert {:error, :invalid} = Admin.authenticate("ana@freguesia.test", "errada-errada-errada")

      assert {:error, :invalid} =
               Admin.authenticate("ninguem@freguesia.test", "qualquer-coisa-aqui")
    end
  end

  describe "2FA (TOTP)" do
    test "enrollment: the right code confirms it and it is required from then on" do
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

    test "reloading the enrollment does not change the secret" do
      operator = Fixtures.operator()
      {:ok, first, _} = Admin.start_totp_enrollment(operator)
      {:ok, second, _} = Admin.start_totp_enrollment(first)

      assert first.totp_secret == second.totp_secret
    end

    test "wrong enrollment code does not confirm" do
      {:ok, operator, _} = Admin.start_totp_enrollment(Fixtures.operator())
      assert {:error, :invalid_code} = Admin.confirm_totp_enrollment(operator, "123456x")
    end

    test "an operator without confirmed 2FA does not pass verification" do
      {:ok, operator, _} = Admin.start_totp_enrollment(Fixtures.operator())
      assert {:error, :not_enrolled} = Admin.verify_totp(operator, "123456")
    end
  end

  describe "session" do
    test "a session within 8 hours returns the operator" do
      operator = Fixtures.operator()
      session = %{"operator_id" => operator.id, "operator_at" => System.system_time(:second)}

      assert Admin.fetch_session_operator(session).id == operator.id
    end

    test "a session older than 8 hours expires" do
      operator = Fixtures.operator()
      old = System.system_time(:second) - Admin.session_ttl_seconds() - 1
      session = %{"operator_id" => operator.id, "operator_at" => old}

      assert Admin.fetch_session_operator(session) == nil
    end

    test "without a session there is no operator" do
      assert Admin.fetch_session_operator(%{}) == nil
    end
  end

  describe "audit_log" do
    test "record_audit writes the row" do
      operator = Fixtures.operator()

      assert {:ok, entry} =
               Admin.record_audit(operator, "teste.acao", "place", "abc", %{"a" => 1}, %{"a" => 2})

      assert entry.admin_id == operator.id
      assert [_] = Admin.audit_entries("place", "abc")
    end

    test "the database does not allow updating or deleting an audit_log row" do
      {:ok, _entry} = Admin.record_audit(nil, "teste.imutavel", "place", "x", nil, nil)

      assert_raise Postgrex.Error, ~r/audit_log is immutable/, fn ->
        Repo.update_all(AuditEntry, set: [action: "adulterado"])
      end
    end
  end
end
