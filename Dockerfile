# Use Tomcat 9 with JDK 11 as the base image
FROM tomcat:9.0-jdk11-openjdk

# Remove the default Tomcat applications
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy the WAR file from your target directory to Tomcat's webapps directory
COPY target/my-webapp.war /usr/local/tomcat/webapps/ROOT.war

# Expose port 8080
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]