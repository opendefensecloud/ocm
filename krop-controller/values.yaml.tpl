{{- $image := index .OCIResources "krop-controller-image" }}
image:
  repository: "{{ $image.Host }}/{{ $image.Repository }}"
  tag: "{{ $image.Tag }}"
