ln -sf ~/.config/nvim/.short.sh ~/.short.sh

grep -qxF 'source ~/.short.sh' ~/.zshrc || echo 'source ~/.short.sh' >> ~/.zshrc

