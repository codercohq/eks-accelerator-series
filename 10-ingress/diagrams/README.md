# EP10 diagrams

Editable source for the Episode 10 diagram. Open `ep10-ingress.drawio` in [draw.io](https://app.diagrams.net) and export to PNG or SVG for slides.

One page, the front door: a user reaching the app through Route 53, the NLB and Traefik, with the one Ingress object read by the three controllers underneath.

Colour key: blue is the user, orange is the AWS edge (NLB and Route 53), green is Traefik and the app, purple is cert-manager, red is the Ingress object at the centre.
