resource "google_compute_network" "vpc_network" {
  name                    = "geth-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "geth-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/20"]
}

# Allow Geth P2P traffic
resource "google_compute_firewall" "allow_geth_p2p" {
  name    = "allow-geth-p2p"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["30303"]
  }

  allow {
    protocol = "udp"
    ports    = ["30303"]
  }

  target_tags = ["geth-node"]
}