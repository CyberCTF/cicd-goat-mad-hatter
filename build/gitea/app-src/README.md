# teaparty

A tiny helper for Wonderland's never-ending tea party. Seats keep shifting — "Clean cup! Move
down!" — so this package works out who sits where and keeps the Hatter's famous riddle on hand.

```python
from teaparty.table import TeaTable

table = TeaTable(["Hatter", "Hare", "Dormouse"])
table.move_down()          # everyone shifts one seat to the right
table.seat_of("Hatter")    # -> 1
```

```python
from teaparty.riddle import ask
ask()   # -> "Why is a raven like a writing desk?"
```

## Development

```bash
python3 -m venv venv && . venv/bin/activate
make        # lint + unit tests
```

CI runs on Wonderland's Jenkins. The build pipeline is kept in a separate repository and invokes
this project's `Makefile`.
