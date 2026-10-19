"""The tea table: who sits where, and the Hatter's "move down" shuffle."""

from dataclasses import dataclass, field
from typing import List


@dataclass
class TeaTable:
    """A round table of guests. ``move_down`` shifts everyone one seat along."""

    guests: List[str] = field(default_factory=list)

    def seat_of(self, guest: str) -> int:
        """Return the seat index currently held by ``guest``."""
        return self.guests.index(guest)

    def move_down(self) -> None:
        """"Clean cup! Move down!" — rotate every guest one seat to the right."""
        if self.guests:
            self.guests = [self.guests[-1], *self.guests[:-1]]

    def neighbour_of(self, guest: str) -> str:
        """Return the guest seated immediately to the right of ``guest``."""
        i = self.seat_of(guest)
        return self.guests[(i + 1) % len(self.guests)]
