all:

install:
	install -D brainslug.rb $(DESTDIR)/usr/bin/brainslug.rb
	install -D brainslug.desktop $(DESTDIR)/usr/share/applications/brainslug.desktop
	install -D brainslug.png $(DESTDIR)/usr/share/icons/hicolor/512x512/brainslug.png
