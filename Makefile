.PHONY: all install git pandoc

THEME ?= "simple"
TRANSITION ?= "none"

all: install pandoc

install:
	stack install pandoc

git:
	git submodule init && git submodule update

pandoc: git
	cat 01_eth.md 02_ps.md 03_web3.md > index.md
	pandoc -t revealjs -s -o index.html -V theme=$(THEME) -V transition=$(TRANSITION) index.md
	rm -f index.md
