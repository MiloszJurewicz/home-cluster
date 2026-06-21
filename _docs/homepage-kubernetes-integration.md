# Homepage Kubernetes Integration

Official docs: https://github.com/gethomepage/homepage/blob/main/docs/configs/kubernetes.md

## Prerequisites

Enable ingress-based service discovery in `values/homepage.values.yaml`:

```yaml
config:
  kubernetes:
    mode: cluster
    ingress: true
```

Also ensure RBAC is enabled so homepage can read Ingress resources across namespaces:

```yaml
enableRbac: true
serviceAccount:
  create: true
```

## Ingress Annotations

Add these annotations to any `Ingress` resource to have it automatically appear in homepage:

```yaml
annotations:
  gethomepage.dev/enabled: "true"
  gethomepage.dev/name: My App
  gethomepage.dev/description: Short description
  gethomepage.dev/group: Services
  gethomepage.dev/icon: myapp.png          # from dashboard-icons pack
  gethomepage.dev/href: "https://home.arpa/myapp"  # set explicitly if path-based routing
  gethomepage.dev/pod-selector: "app=myapp"        # if pods don't use app.kubernetes.io/name label
```

### `gethomepage.dev/href` — always set explicitly for path-based routes

Homepage infers the href from the ingress host only (e.g. `https://home.arpa`), **not** the path.
If the service is served under a sub-path (e.g. `home.arpa/myapp`), the link will be wrong without this annotation.

### `gethomepage.dev/pod-selector` — required when pods use custom labels

Homepage derives the pod health selector from `app.kubernetes.io/name=<ingress-name>` by default.
If pods are labelled differently (e.g. `app: myapp`), set this explicitly:

```yaml
gethomepage.dev/pod-selector: "app=myapp"
```

Without it, homepage shows **"not found"** next to the service icon.

### Icons

Icons are resolved from the [walkxcode/dashboard-icons](https://github.com/walkxcode/dashboard-icons) pack.
Reference them by filename without the extension, or with `.png`/`.svg`:

```yaml
gethomepage.dev/icon: nginx.png
gethomepage.dev/icon: nginx        # also works
gethomepage.dev/icon: mdi-web      # Material Design Icon fallback
gethomepage.dev/icon: https://...  # external URL
```

## Example — Nginx with path-based routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: default-ngnix-strip-prefix@kubernetescrd
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: Nginx
    gethomepage.dev/description: Nginx Test
    gethomepage.dev/group: Services
    gethomepage.dev/icon: nginx.png
    gethomepage.dev/href: "https://home.arpa/ngnix"
    gethomepage.dev/pod-selector: "app=nginx"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - home.arpa
  rules:
    - host: home.arpa
      http:
        paths:
          - path: /ngnix
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
```

