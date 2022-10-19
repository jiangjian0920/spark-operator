#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
ARG java_image_tag=8-jdk

FROM openjdk:${java_image_tag} as base
ARG spark_uid=2023
# Before building the docker image, first build and make a Spark distribution following
# the instructions in http://spark.apache.org/docs/latest/building-spark.html.
# If this docker file is being used in the context of building your images from a Spark
# distribution, the docker build command should be invoked from the top level directory
# of the Spark distribution. E.g.:
# docker build -t spark:latest -f kubernetes/dockerfiles/spark/Dockerfile .

RUN set -ex && \
    apk upgrade --no-cache && \
    apk add --no-cache bash tini libc6-compat linux-pam && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd

FROM base as spark
### Download Spark Distribution ###
WORKDIR /opt
RUN wget https://archive.apache.org/dist/spark/spark-2.4.0/spark-2.4.0-bin-hadoop2.7.tgz
RUN tar xvf spark-2.4.0-bin-hadoop2.7.tgz

FROM spark as build
### Create target directories ###
RUN mkdir -p /opt/spark/jars

### Set Spark dir ARG for use Docker build context on root project dir ###
FROM base as final
ARG spark_dir=/opt/spark-2.4.0-bin-hadoop2.7

### Copy files from the build image ###
COPY --from=build ${spark_dir}/jars /opt/spark/jars
COPY --from=build ${spark_dir}/bin /opt/spark/bin
COPY --from=build ${spark_dir}/sbin /opt/spark/sbin
COPY --from=build ${spark_dir}/kubernetes/dockerfiles/spark/entrypoint.sh /opt/
#COPY --from=build ${spark_dir}/kubernetes/dockerfiles/spark/decom.sh /opt/
COPY --from=build ${spark_dir}/examples /opt/spark/examples
COPY --from=build ${spark_dir}/kubernetes/tests /opt/spark/tests
COPY --from=build ${spark_dir}/data /opt/spark/data

RUN rm  /opt/spark/jars/kubernetes-client-3.0.0.jar
RUN rm  /opt/spark/jars/kubernetes-model-2.0.0.jar
RUN rm /opt/spark/jars/okhttp-3.8.1.jar
RUN rm /opt/spark/jars/okio-1.13.0.jar
ADD https://repo1.maven.org/maven2/io/fabric8/kubernetes-client/4.6.1/kubernetes-client-4.6.1.jar /opt/spark/jars
ADD https://repo1.maven.org/maven2/io/fabric8/kubernetes-model-common/4.6.1/kubernetes-model-common-4.6.1.jar /opt/spark/jars
ADD https://repo1.maven.org/maven2/io/fabric8/kubernetes-model/4.6.1/kubernetes-model-4.6.1.jar /opt/spark/jars
ADD okhttp-3.12.0.jar  /opt/spark/jars/
ADD okio-1.15.0.jar  /opt/spark/jars/

RUN chown 1000:1000 /opt/spark/jars/okhttp-3.12.0.jar
RUN chown 1000:1000 /opt/spark/jars/okio-1.15.0.jar
RUN chown 1000:1000 /opt/spark/jars/kubernetes-client-4.6.1.jar
RUN chown 1000:1000 /opt/spark/jars/kubernetes-model-common-4.6.1.jar
RUN chown 1000:1000 /opt/spark/jars/kubernetes-model-4.6.1.jar
RUN chmod 644 /opt/spark/jars/okhttp-3.12.0.jar
RUN chmod 644 /opt/spark/jars/okio-1.15.0.jar
RUN chmod 644 /opt/spark/jars/kubernetes-client-4.6.1.jar
RUN chmod 644 /opt/spark/jars/kubernetes-model-common-4.6.1.jar
RUN chmod 644 /opt/spark/jars/kubernetes-model-4.6.1.jar
WORKDIR /opt/spark/work-dir
ENV SPARK_HOME /opt/spark
RUN echo 'zndw:x:2023:0::/home/zndw:/bin/bash' >> /etc/passwd
WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir
#RUN chmod a+x /opt/decom.sh
RUN chmod a+x /opt/entrypoint.sh
ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}
