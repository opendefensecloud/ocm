{{- $controller := index .OCIResources "quota-controller-image" }}
controller:
  image:
    repository: "{{ $controller.Host }}/{{ $controller.Repository }}"
    tag: "{{ $controller.Tag }}"

{{- $webhook := index .OCIResources "quota-webhook-image" }}
webhook:
  image:
    repository: "{{ $webhook.Host }}/{{ $webhook.Repository }}"
    tag: "{{ $webhook.Tag }}"
