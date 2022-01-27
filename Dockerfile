FROM ubuntu:focal

ARG USER_ID
ARG GROUP_ID

RUN apt-get update && \
	apt-get install -y wget \
		build-essential \
		rsync \
		pax

RUN wget https://github.com/debbuild/debbuild/archive/20.04.0.tar.gz && \
	tar -zxvf 20.04.0.tar.gz && \
	cd debbuild-20.04.0 && \
	./configure && \
	make && \
	make install && \
	cd / && \
	rm -r debbuild-20.04.0 20.04.0.tar.gz

RUN addgroup --gid $GROUP_ID user && adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
USER user

COPY --chown=user:user . /bdsnap

RUN cd bdsnap && \
	chmod +x entry.sh

ENTRYPOINT ["/bdsnap/entry.sh"]
