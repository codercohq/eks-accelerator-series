# EP10 diagrams

Editable source for the Episode 10 diagrams. Open them in [draw.io](https://app.diagrams.net) and export to PNG or SVG for slides.

## ep10-ingress.drawio

The front door: a user reaching the app through Route 53, the NLB and Traefik, with the one Ingress object read by the three controllers underneath.

Colour key: blue is the user, orange is the AWS edge (NLB and Route 53), green is Traefik and the app, purple is cert-manager, red is the Ingress object at the centre.

## ep10-gateway-api.drawio

Ingress next to the Gateway API, showing how the one Ingress object splits into a GatewayClass, a Gateway and per-team HTTPRoutes.

Colour key: red is the single Ingress, blue is the platform-owned GatewayClass and Gateway, amber is the app-owned HTTPRoutes, green is the services.
