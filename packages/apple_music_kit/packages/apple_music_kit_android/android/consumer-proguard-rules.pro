# Apple MusicKit Android SDK
-keep class com.apple.android.sdk.authentication.** { *; }
-keep class com.apple.android.music.playback.** { *; }
-dontwarn com.apple.**

# MediaPlayback bundles JavaCPP's Maven tooling and opt-in JMX and SLF4J helpers.
-dontwarn java.lang.management.BufferPoolMXBean
-dontwarn java.lang.management.ManagementFactory
-dontwarn javax.management.InstanceAlreadyExistsException
-dontwarn javax.management.MBeanRegistrationException
-dontwarn javax.management.MBeanServer
-dontwarn javax.management.MalformedObjectNameException
-dontwarn javax.management.NotCompliantMBeanException
-dontwarn javax.management.ObjectInstance
-dontwarn javax.management.ObjectName
-dontwarn org.apache.maven.artifact.Artifact
-dontwarn org.apache.maven.plugin.AbstractMojo
-dontwarn org.apache.maven.plugin.MojoExecutionException
-dontwarn org.apache.maven.plugin.descriptor.PluginDescriptor
-dontwarn org.apache.maven.plugin.logging.Log
-dontwarn org.apache.maven.project.MavenProject
-dontwarn org.slf4j.Logger
-dontwarn org.slf4j.LoggerFactory
