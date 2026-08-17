# EP8 diagrams

Editable source for the Episode 8 diagram. Open `ep8-secrets.drawio` in [draw.io](https://app.diagrams.net) and export to PNG or SVG for slides.

One page, the External Secrets flow: Secrets Manager to the operator to the synced Kubernetes Secret to the pod, with the ExternalSecret driving it.

Colour key: amber is the external store, blue is the operator, green is the objects you write and the Secret it produces, grey is the app that does not change.
