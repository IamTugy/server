grafana:
  enabled: true
  adminPassword: "${grafana_admin_password}"

  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - grafana.local.dev
    path: /

  persistence:
    enabled: false  # ephemeral for local dev — set true with a storageClass for persistence

  sidecar:
    dashboards:
      enabled: true

prometheus:
  prometheusSpec:
    retention: 7d
    # Scrape ServiceMonitors and PodMonitors across all namespaces
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    podMonitorSelectorNilUsesHelmValues: false
    podMonitorSelector: {}
    podMonitorNamespaceSelector: {}
    resources:
      requests:
        memory: 400Mi
        cpu: 100m
      limits:
        memory: 1Gi
        cpu: 500m

alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests:
        memory: 64Mi
      limits:
        memory: 256Mi

# k3s uses SQLite (not etcd) and embeds scheduler/controller-manager.
# Disable the scrape targets for these components to avoid failed scrapes.
kubeEtcd:
  enabled: false
kubeScheduler:
  enabled: false
kubeControllerManager:
  enabled: false
kubeProxy:
  enabled: false

# These are valuable for local observability
nodeExporter:
  enabled: true

kube-state-metrics:
  enabled: true
