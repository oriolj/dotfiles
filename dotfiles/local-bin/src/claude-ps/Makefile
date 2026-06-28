BIN := claude-ps
PREFIX := $(HOME)/.local/bin

.PHONY: build install clean run

build: ## Compile the binary into ./$(BIN)
	@echo -e "\033[1;34m==> building $(BIN)\033[0m"
	@go build -trimpath -ldflags "-s -w" -o $(BIN) .

install: ## Build and install into ~/.local/bin
	@echo -e "\033[1;34m==> installing $(BIN) -> $(PREFIX)\033[0m"
	@go build -trimpath -ldflags "-s -w" -o $(PREFIX)/$(BIN) .
	@echo -e "\033[1;32m==> done: $(PREFIX)/$(BIN)\033[0m"

run: ## Build and run (human-readable output)
	@go run .

clean: ## Remove the locally-built binary
	@rm -f $(BIN)
