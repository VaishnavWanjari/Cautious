"""Working-day calendar arithmetic.

A :class:`WorkCalendar` knows which weekdays are working days and which
specific dates are holidays, and can move forward/backward by a number of
working days. Durations in the scheduling engine are expressed in working
days, so all date math funnels through this class to correctly skip
weekends and holidays.

Convention used by the scheduler
--------------------------------
Activity dates are *inclusive working-day* spans. An activity that starts on
a working day ``d`` and has duration ``n`` (>= 1) working days finishes on
``add_working_days(d, n - 1)`` — i.e. a 1-day activity starts and finishes on
the same day. ``working_days_between`` is the inclusive count used to invert
that relationship.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta


@dataclass
class WorkCalendar:
    """A working-day calendar.

    Parameters
    ----------
    working_weekdays:
        ISO weekday numbers that count as working days (Mon=1 .. Sun=7).
        Defaults to Monday-Friday.
    holidays:
        Specific calendar dates that are non-working regardless of weekday.
    """

    working_weekdays: set[int] = field(default_factory=lambda: {1, 2, 3, 4, 5})
    holidays: set[date] = field(default_factory=set)

    # --- predicates ------------------------------------------------------
    def is_working_day(self, d: date) -> bool:
        return d.isoweekday() in self.working_weekdays and d not in self.holidays

    # --- snapping --------------------------------------------------------
    def next_working_day(self, d: date) -> date:
        """Return ``d`` if it is a working day, else the next working day."""
        cur = d
        for _ in range(3650):  # ~10 years guard against an empty calendar
            if self.is_working_day(cur):
                return cur
            cur += timedelta(days=1)
        raise ValueError("No working days found within 10 years — check calendar")

    def prev_working_day(self, d: date) -> date:
        """Return ``d`` if it is a working day, else the previous working day."""
        cur = d
        for _ in range(3650):
            if self.is_working_day(cur):
                return cur
            cur -= timedelta(days=1)
        raise ValueError("No working days found within 10 years — check calendar")

    # --- arithmetic ------------------------------------------------------
    def add_working_days(self, start: date, days: int) -> date:
        """Move ``days`` working days from ``start`` (snapped to a working day).

        ``days`` may be negative to move backwards. ``days == 0`` returns the
        working-day snap of ``start`` itself.
        """
        cur = self.next_working_day(start) if days >= 0 else self.prev_working_day(start)
        step = 1 if days >= 0 else -1
        remaining = abs(days)
        while remaining > 0:
            cur += timedelta(days=step)
            if self.is_working_day(cur):
                remaining -= 1
        return cur

    def working_days_between(self, start: date, finish: date) -> int:
        """Inclusive count of working days in ``[start, finish]``.

        Returns 0 if ``finish`` is before ``start``.
        """
        if finish < start:
            return 0
        count = 0
        cur = start
        while cur <= finish:
            if self.is_working_day(cur):
                count += 1
            cur += timedelta(days=1)
        return count

    def finish_of(self, start: date, duration_days: int) -> date:
        """Inclusive finish date for an activity of ``duration_days`` working days."""
        n = max(1, int(duration_days))
        return self.add_working_days(start, n - 1)

    def start_of(self, finish: date, duration_days: int) -> date:
        """Inclusive start date given an activity finish and its duration."""
        n = max(1, int(duration_days))
        return self.add_working_days(finish, -(n - 1))
