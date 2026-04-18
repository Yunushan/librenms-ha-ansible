.PHONY: install lint standalone cluster validate

install:
	ansible-galaxy collection install -r requirements.yml

lint:
	yamllint .
	ansible-lint

standalone:
	ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml

cluster:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml

validate:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
