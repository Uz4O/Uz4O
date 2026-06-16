from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.auth.models import Account, AuthSmsCode
from app.auth.repository import create_sms_code, login_with_sms_code
from app.db import Base


def test_login_with_sms_code_creates_account_and_consumes_code() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        create_sms_code(session, phone="13800138000", code="123456")
        account = login_with_sms_code(session, phone="13800138000", code="123456")

        assert account is not None
        assert account.phone == "13800138000"
        assert session.scalar(select(Account).where(Account.phone == "13800138000")) is not None
        sms_code = session.scalar(select(AuthSmsCode))
        assert sms_code is not None
        assert sms_code.consumed_at is not None


def test_login_with_wrong_sms_code_is_rejected() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        create_sms_code(session, phone="13800138000", code="123456")

        assert login_with_sms_code(session, phone="13800138000", code="000000") is None
        assert session.scalar(select(Account)) is None


def test_creating_new_sms_code_invalidates_previous_unconsumed_codes() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        first = create_sms_code(session, phone="13800138000", code="111111")

        second = create_sms_code(session, phone="13800138000", code="222222")

        session.refresh(first)
        assert first.consumed_at is not None
        assert second.consumed_at is None
        assert login_with_sms_code(session, phone="13800138000", code="111111") is None
        assert login_with_sms_code(session, phone="13800138000", code="222222") is not None


def test_recreating_same_sms_code_after_login_refreshes_existing_record() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        first = create_sms_code(session, phone="13800138000", code="123456")
        assert login_with_sms_code(session, phone="13800138000", code="123456") is not None
        session.refresh(first)
        assert first.consumed_at is not None

        refreshed = create_sms_code(session, phone="13800138000", code="123456")

        assert refreshed.id == first.id
        assert refreshed.consumed_at is None
        assert login_with_sms_code(session, phone="13800138000", code="123456") is not None
