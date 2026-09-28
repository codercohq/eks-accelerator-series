# EP11 diagrams

Editable source for the Episode 11 diagram. Open `ep11-events.drawio` in [draw.io](https://app.diagrams.net) and export to PNG or SVG for slides.

One page, the event bus: the producer sending to the queue, the worker consuming, a poison message dropping into the dead-letter queue and the alarm on it.

Colour key: blue is the producer, amber is the queue, green is the worker, red is the DLQ, purple is the alarm.
