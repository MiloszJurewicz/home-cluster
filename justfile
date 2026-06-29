# Pull root CA cert + key from Bitwarden and write them to certs/
cert-pull:
	@echo "Pulling root CA certificate from Bitwarden..."
	bw get notes f7a39b6e-b649-4f77-a667-b47701763552 > certs/root-ca.crt
	@echo "Pulling root CA key from Bitwarden..."
	bw get notes bb363f30-fc76-410a-b0e4-b477017646b8 > certs/root-ca.key
	chmod 600 certs/root-ca.key
	@echo "Done: certs/root-ca.crt, certs/root-ca.key"

# Write Netbird PAT from Bitwarden to terraform/netbird/netbird.auto.tfvars.json
netbird-pat:
	@scripts/netbird-pat.sh

# Apply nft rules so Netbird-routed traffic reaches k3s pods
netbird-k3s-fix:
	sudo nft -f scripts/netbird-k3s-fix.nft
