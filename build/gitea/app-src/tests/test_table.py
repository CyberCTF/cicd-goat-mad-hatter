from teaparty.riddle import ask
from teaparty.table import TeaTable


def test_move_down_rotates_seats():
    table = TeaTable(["Hatter", "Hare", "Dormouse"])
    table.move_down()
    assert table.guests == ["Dormouse", "Hatter", "Hare"]
    assert table.seat_of("Hatter") == 1


def test_neighbour_wraps_around():
    table = TeaTable(["Hatter", "Hare", "Dormouse"])
    assert table.neighbour_of("Dormouse") == "Hatter"


def test_riddle_has_no_answer():
    assert ask() == "Why is a raven like a writing desk?"
