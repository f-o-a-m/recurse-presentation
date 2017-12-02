.PHONY: all install git pandoc

all: pandoc

install:
	stack install pandoc

git:
	git submodule init && git submodule checkout

pandoc:
	cat 01_eth.md 02_ps.md 03_web3.md > index.md
	pandoc -t revealjs -s -o index.html index.md
	rm -f index.md