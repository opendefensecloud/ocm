{{- $controller := index .OCIResources "dependency-controller-image" }}
controller:
  image:
    repository: "{{ $controller.Host }}/{{ $controller.Repository }}"
    tag: "{{ $controller.Tag }}"

{{- $webhook := index .OCIResources "dependency-webhook-image" }}
webhook:
  image:
    repository: "{{ $webhook.Host }}/{{ $webhook.Repository }}"
    tag: "{{ $webhook.Tag }}"
