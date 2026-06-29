# Pull root CA cert + key from Bitwarden and write them to certs/
cert-pull:
	@echo "Pulling root CA certificate from Bitwarden..."
	bw get notes f7a39b6e-b649-4f77-a667-b47701763552 > certs/root-ca.crt
	@echo "Pulling root CA key from Bitwarden..."
	bw get notes bb363f30-fc76-410a-b0e4-b477017646b8 > certs/root-ca.key
	chmod 600 certs/root-ca.key
	@echo "Done: certs/root-ca.crt, certs/root-ca.key"
