"""Tests for working-day calendar arithmetic (pure stdlib)."""

from datetime import date

from app.domain.calendar import WorkCalendar


def test_skips_weekends_mon_fri():
    cal = WorkCalendar()  # Mon-Fri
    fri = date(2027, 1, 15)  # Friday
    assert fri.isoweekday() == 5
    # one working day after Friday is Monday
    assert cal.add_working_days(fri, 1) == date(2027, 1, 18)


def test_zero_days_snaps_to_working_day():
    cal = WorkCalendar()
    sat = date(2027, 1, 16)  # Saturday
    assert cal.add_working_days(sat, 0) == date(2027, 1, 18)  # next Monday
    assert cal.prev_working_day(sat) == date(2027, 1, 15)  # prev Friday


def test_holidays_are_non_working():
    cal = WorkCalendar(holidays={date(2027, 1, 1)})
    # 2027-01-01 is a Friday holiday; next working day is Monday 4th
    assert cal.is_working_day(date(2027, 1, 1)) is False
    assert cal.next_working_day(date(2027, 1, 1)) == date(2027, 1, 4)


def test_inclusive_finish_and_start():
    cal = WorkCalendar()
    start = date(2027, 1, 18)  # Monday
    # 5-day activity Mon..Fri inclusive
    assert cal.finish_of(start, 5) == date(2027, 1, 22)
    # 1-day activity finishes same day
    assert cal.finish_of(start, 1) == start
    # inverse
    assert cal.start_of(date(2027, 1, 22), 5) == start


def test_working_days_between_inclusive():
    cal = WorkCalendar()
    # Mon..Fri inclusive = 5 working days
    assert cal.working_days_between(date(2027, 1, 18), date(2027, 1, 22)) == 5
    # spanning a weekend: Fri..next Mon = 2 working days
    assert cal.working_days_between(date(2027, 1, 15), date(2027, 1, 18)) == 2


def test_six_day_week():
    cal = WorkCalendar(working_weekdays={1, 2, 3, 4, 5, 6})  # Sat is working
    fri = date(2027, 1, 15)
    assert cal.add_working_days(fri, 1) == date(2027, 1, 16)  # Saturday counts
