ARG java_image_tag=8-jdk

FROM openjdk:${java_image_tag} as base

ARG spark_uid=2023

RUN set -ex && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y bash tini libc6 libpam-modules libnss3 && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/*

FROM base as spark
### Download Spark Distribution ###
WORKDIR /opt
RUN wget https://archive.apache.org/dist/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz
RUN tar xvf spark-2.4.8-bin-hadoop2.7.tgz

FROM spark as build
### Create target directories ###
RUN mkdir -p /opt/spark/jars
RUN mkdir -p /opt/spark/conf
### Set Spark dir ARG for use Docker build context on root project dir ###
FROM base as final
ARG spark_dir=/opt/spark-2.4.8-bin-hadoop2.7

### Copy files from the build image ###
COPY --from=build ${spark_dir}/jars /opt/spark/jars
COPY --from=build ${spark_dir}/bin /opt/spark/bin
COPY --from=build ${spark_dir}/sbin /opt/spark/sbin
COPY --from=build ${spark_dir}/kubernetes/dockerfiles/spark/entrypoint.sh /opt/
#COPY --from=build ${spark_dir}/kubernetes/dockerfiles/spark/decom.sh /opt/
COPY --from=build ${spark_dir}/examples /opt/spark/examples
COPY --from=build ${spark_dir}/kubernetes/tests /opt/spark/tests
COPY --from=build ${spark_dir}/data /opt/spark/data
COPY --from=build ${spark_dir}/kubernetes/dockerfiles/spark/entrypoint.sh /opt/spark/conf

WORKDIR /opt/spark/work-dir
ENV SPARK_HOME /opt/spark
RUN echo 'test01:x:2023:2023::/home/test01:/bin/sh' >> /etc/passwd
WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir
#RUN chmod a+x /opt/decom.sh

ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}

