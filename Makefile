
SOCKETF=node_network_details.socket
SERVICEF=node_network_details@.service
# where it is
SYSTEMD=/etc/systemd/system
# where you want it
BIN_D=/usr/local/bin
SCRIPT=node_network_details.sh

all:
	@echo \"make install\" or \"make uninstall\", thats all we got

install: $(SYSTEMD)/$(SOCKETF) $(SYSTEMD)/$(SERVICEF) $(BIN_D)/$(SCRIPT) Makefile
	systemctl daemon-reload
	systemctl enable $(SOCKETF)
	systemctl start $(SOCKETF)

uninstall: $(SYSTEMD)/$(SOCKETF) $(SYSTEMD)/$(SERVICEF)
	rm -f $(SYSTEMD)/$(SOCKETF) $(SYSTEMD)/$(SERVICEF) $(BIN_D)/$(SCRIPT)
	systemctl daemon-reload

restart:
	systemctl restart $(SOCKETF)
	systemctl restart $(SERVICEF)

$(SYSTEMD)/$(SOCKETF): $(SOCKETF)
	cp $(SOCKETF) $(SYSTEMD)/$(SOCKETF)

$(SYSTEMD)/$(SERVICEF): $(SERVICEF)
	cp $(SERVICEF) $(SYSTEMD)/$(SERVICEF)

$(BIN_D)/$(SCRIPT): $(SCRIPT)
	cp $(SCRIPT) $(BIN_D)/
	chmod a+x $(BIN_D)/$(SCRIPT)
