# Io module

HEADERS += $$SK_CORE/io/WAbstractLoader.h \
           $$SK_CORE/io/WAbstractLoader_p.h \
           $$SK_CORE/io/WLoaderNetwork.h \
           $$SK_CORE/io/WLoaderNetwork_p.h \
           $$SK_CORE/io/WLocalObject.h \
           $$SK_CORE/io/WLocalObject_p.h \
           $$SK_CORE/io/WFileWatcher.h \
           $$SK_CORE/io/WFileWatcher_p.h \
           $$SK_CORE/io/WCache.h \
           $$SK_CORE/io/WCache_p.h \
           $$SK_CORE/io/WUnzipper.h \
           $$SK_CORE/io/WYamlReader.h \
           $$SK_TORRENT/io/WLoaderTorrent.h \
           $$SK_TORRENT/io/WLoaderTorrent_p.h \
           $$SK_BACKEND/io/WBackendCache.h \
           src/io/DataLocal.h \
           src/io/DataOnline.h \

SOURCES += $$SK_CORE/io/WAbstractLoader.cpp \
           $$SK_CORE/io/WLoaderNetwork.cpp \
           $$SK_CORE/io/WLocalObject.cpp \
           $$SK_CORE/io/WFileWatcher.cpp \
           $$SK_CORE/io/WCache.cpp \
           $$SK_CORE/io/WUnzipper.cpp \
           $$SK_CORE/io/WYamlReader.cpp \
           $$SK_TORRENT/io/WLoaderTorrent.cpp \
           $$SK_BACKEND/io/WBackendCache.cpp \
           src/io/DataLocal.cpp \
           src/io/DataOnline.cpp \
