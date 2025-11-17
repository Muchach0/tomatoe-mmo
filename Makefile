@PHONY: all build run clean export-client-html docker-client-build-run docker-client-run docker-client-rm docker-client-update gcp-trigger-build gcp-init-dns

DOCKER_IMAGE_CLIENT = muchachoo/tomatoe-mmo
DOCKER_IMAGE_SERVER = muchachoo/tomatoe-mmo-server
DOCKER_IMAGE_TAG = 1
GCP_CLOUD_RUN_SERVICE_CLIENT = tomatoe-mmo-client
GCP_CLOUD_RUN_SERVICE_SERVER = tomatoe-mmo-server
DNS_ZONE = muchacho-app
DNS_NAME_CLIENT = tomatoe-mmo.muchacho.app
DNS_NAME_SERVER = tomatoe-mmo-server.muchacho.app

CURRENT_BUILD_VERSION_FILE_PATH = builds/build_version.cfg
CURRENT_VERSION = $(shell cat $(CURRENT_BUILD_VERSION_FILE_PATH))
NEXT_VERSION = $(shell echo $$(($(CURRENT_VERSION) + 1)))
DOCKER_IMAGE_VERSION = v$(NEXT_VERSION)
LINUX_BINARY = tomatoe-mmo_linux_export.x86_64


# ========================== LOCAL CLIENT SECTION (no docker) =========================
export-linux:
	../Godot_v4.5-stable_linux.x86_64 --headless --path $(shell pwd) --export-release "Linux" $(shell pwd)/builds/linux/$(LINUX_BINARY)

export-client-html:
	../Godot_v4.5-stable_linux.x86_64 --headless --path $(shell pwd) --export-release "Web" $(shell pwd)/builds/client-html/index.html

run-server-linux: 
	$(shell pwd)/builds/linux/$(LINUX_BINARY) --server

run-client-linux: 
	$(shell pwd)/builds/linux/$(LINUX_BINARY) --local

export-then-run-server-client: export-linux
	konsole --noclose  -e $(shell pwd)/builds/linux/$(LINUX_BINARY) --server &
	konsole --noclose  -e $(shell pwd)/builds/linux/$(LINUX_BINARY) --local & 
	konsole --noclose  -e $(shell pwd)/builds/linux/$(LINUX_BINARY) --local

# ========================== CLIENT HTML DOCKER SECTION =========================
docker-client-build-run: export-client-html ## Build client container
	docker build -f builds/Dockerfile-client -t godot-client .
	docker run --name=godot-client --restart unless-stopped --network host --volume "$(shell pwd)/logs:/tmp/logs" -d -t godot-client
	xdg-open https://127.0.0.1

docker-client-run: ## Run client container
	docker run --name=godot-client --restart unless-stopped --network host --volume "$(shell pwd)/logs:/tmp/logs" -d -t godot-client
	xdg-open https://127.0.0.1

docker-client-rm:
	docker container stop godot-client
	docker container rm godot-client
	docker image rm godot-client

docker-client-update: docker-client-rm docker-client-build-run


# ========================== SERVER HTML DOCKER SECTION =========================
docker-server-build-run: export-linux
	docker build -f builds/Dockerfile-server -t godot-server .
	docker run --name=godot-server --restart unless-stopped -p 10567:10567/tcp -d -t godot-server

docker-server-run:
	docker run --name=godot-server --restart unless-stopped -p 10567:10567/tcp -d -t godot-server

docker-server-rm:
	docker container stop godot-server
	docker container rm godot-server
	docker image rm godot-server

docker-server-update: docker-server-rm docker-server-build-run

docker-server-pull-and-run:
	docker pull $(DOCKER_IMAGE_SERVER):v2
	docker run --name=godot-server --restart unless-stopped -p 10567:10567/tcp -d -t $(DOCKER_IMAGE_SERVER):v2



# =========================== GCP SECTION ===========================
push-new-docker-image-client:
	docker build -t $(DOCKER_IMAGE_CLIENT):$(DOCKER_IMAGE_VERSION) -f builds/Dockerfile-client .
	docker push $(DOCKER_IMAGE_CLIENT):$(DOCKER_IMAGE_VERSION)
	echo $(NEXT_VERSION) > $(CURRENT_BUILD_VERSION_FILE_PATH)
	@echo "Updated version to: $(NEXT_VERSION)"

push-new-docker-image-server:
	docker build -t $(DOCKER_IMAGE_SERVER):$(DOCKER_IMAGE_VERSION) -f builds/Dockerfile-server .
	docker push $(DOCKER_IMAGE_SERVER):$(DOCKER_IMAGE_VERSION)
	echo $(NEXT_VERSION) > $(CURRENT_BUILD_VERSION_FILE_PATH)
	@echo "Updated version to: $(NEXT_VERSION)"

add-google-analytics:
	@echo "Adding Google Analytics to client HTML"
	# awk '/<\/head>/ { system("cat $(shell pwd)/builds/google_analytics.html"); print; next } { print }' builds/client-html/index.html > temp.html  && mv temp.html builds/client-html/index.html

# gcp-init-docker-registry: 
# 	gcloud artifacts repositories create my-dungeon-game --repository-format=docker --location=europe-west1 --description="My Snake Game Docker Repository"

gcp-trigger-build-client: export-client-html add-google-analytics push-new-docker-image-client ## Trigger GCP build
	@echo "Using Docker image:  $(DOCKER_IMAGE_CLIENT):v$(CURRENT_VERSION)"
	gcloud run deploy $(GCP_CLOUD_RUN_SERVICE_CLIENT) \
          --image $(DOCKER_IMAGE_CLIENT):v$(CURRENT_VERSION) \
          --region europe-west1 \
          --platform managed \
          --allow-unauthenticated \
          --max-instances=1 \
          --port 80 \
          --use-http2
	xdg-open https://$(DNS_NAME_CLIENT)

gcp-trigger-build-server: export-linux push-new-docker-image-server ## Trigger GCP build
	@echo "Using Docker image:  $(DOCKER_IMAGE_SERVER):v$(CURRENT_VERSION)"
	gcloud run deploy $(GCP_CLOUD_RUN_SERVICE_SERVER) \
          --image $(DOCKER_IMAGE_SERVER):v$(CURRENT_VERSION) \
          --region europe-west1 \
          --platform managed \
          --allow-unauthenticated \
          --max-instances=1 \
          --port 10567 


gcp-trigger-build-all: gcp-trigger-build-server gcp-trigger-build-client


gcp-init-dns: ## Initialize DNS for GCP
	gcloud dns record-sets transaction start --zone=$(DNS_ZONE)
	gcloud dns record-sets transaction add --zone=$(DNS_ZONE) --name="$(DNS_NAME_CLIENT)" --type=CNAME --ttl=432000 "ghs.googlehosted.com."
	gcloud dns record-sets transaction execute --zone=$(DNS_ZONE)
	gcloud beta run domain-mappings create --service $(GCP_CLOUD_RUN_SERVICE_CLIENT) --domain $(DNS_NAME_CLIENT) --region europe-west1
	
gcp-init-dns-server:
	gcloud dns record-sets transaction start --zone=$(DNS_ZONE)
	gcloud dns record-sets transaction add --zone=$(DNS_ZONE) --name="$(DNS_NAME_SERVER)" --type=CNAME --ttl=432000 "ghs.googlehosted.com."
	gcloud dns record-sets transaction execute --zone=$(DNS_ZONE)
	gcloud beta run domain-mappings create --service $(GCP_CLOUD_RUN_SERVICE_SERVER) --domain $(DNS_NAME_SERVER) --region europe-west1



# =========================== ITCH SECTION ===========================
itch-build-zip: export-client-html
	rm -f builds/client-html.zip
	cd builds && zip -r client-html.zip client-html

