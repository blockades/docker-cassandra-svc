FROM cassandra:2.1
MAINTAINER Dan Hassan <daniel.san@dyne.org>

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
RUN chmod a+x /docker-entrypoint.sh
CMD ["cassandra", "-f"]
