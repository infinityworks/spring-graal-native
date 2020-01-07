#!/usr/bin/env bash

set -e

ARTIFACT=springmvc-tomcat
MAINCLASS=com.example.tomcat.Application
VERSION=0.0.1-SNAPSHOT
FEATURE=$HOME/.m2/repository/org/springframework/experimental/spring-graal-native-feature/0.6.0.BUILD-SNAPSHOT/spring-graal-native-feature-0.6.0.BUILD-SNAPSHOT.jar

ls $FEATURE

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

rm -rf target
mkdir -p target/native-image

echo "Packaging $ARTIFACT with Maven"
./mvnw -DskipTests package > target/native-image/output.txt

JAR="$ARTIFACT-$VERSION.jar"
rm -f $ARTIFACT
echo "Unpacking $JAR"
cd target/native-image
jar -xvf ../$JAR >/dev/null 2>&1
cp -R META-INF BOOT-INF/classes

LIBPATH=`find BOOT-INF/lib | tr '\n' ':'`
CP=BOOT-INF/classes:$LIBPATH:$FEATURE

GRAALVM_VERSION=`native-image --version`
echo "Compiling $ARTIFACT with $GRAALVM_VERSION"
{ time native-image \
  --verbose \
  --no-server \
  --initialize-at-build-time=org.eclipse.jdt,org.apache.el.parser.SimpleNode,javax.servlet.jsp.JspFactory,org.apache.jasper.servlet.JasperInitializer,org.apache.jasper.runtime.JspFactoryImpl \
  --initialize-at-build-time=org.springframework.util.unit.DataSize \
  -H:+JNI \
  -H:EnableURLProtocols=http,jar \
  -H:ReflectionConfigurationFiles=../../tomcat-reflection.json \
  -H:JNIConfigurationFiles=../../tomcat-jni.json \
  --enable-https \
  -H:+TraceClassInitialization \
  -H:Name=$ARTIFACT \
  -H:+ReportExceptionStackTraces \
  --no-fallback \
  --allow-incomplete-classpath \
  --report-unsupported-elements-at-runtime \
  -DremoveUnusedAutoconfig=true \
  -cp $CP $MAINCLASS >> output.txt ; } 2>> output.txt

if [[ -f $ARTIFACT ]]
then
  printf "${GREEN}SUCCESS${NC}\n"
  mv ./$ARTIFACT ..
  exit 0
else
  printf "${RED}FAILURE${NC}: an error occurred when compiling the native-image.\n"
  exit 1
fi

