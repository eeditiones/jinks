# Builds the demo image on top of a jinks image built from this checkout,
# instead of the published ghcr.io/eeditiones/jinks:latest. Used by build.sh
# whenever it builds jinks locally.
#
#   IMAGE=jinks-demo PLATFORMS=linux/amd64,linux/arm64 docker buildx bake demo

variable "IMAGE" {
  default = "jinks-demo"
}

# Comma-separated list, e.g. "linux/amd64,linux/arm64". Empty: host platform.
variable "PLATFORMS" {
  default = ""
}

variable "EXIST_VERSION" {
  default = "6.4.0"
}

target "_platforms" {
  platforms = PLATFORMS == "" ? [] : split(",", PLATFORMS)
}

target "jinks" {
  inherits   = ["_platforms"]
  context    = ".."
  dockerfile = "Dockerfile"
  args = {
    EXIST_VERSION = EXIST_VERSION
  }
  pull = true
}

target "demo" {
  inherits   = ["_platforms"]
  context    = "."
  dockerfile = "Dockerfile.demo"
  args = {
    JINKS_BASE = "jinks"
  }
  contexts = {
    jinks = "target:jinks"
  }
  tags = [IMAGE]
}
