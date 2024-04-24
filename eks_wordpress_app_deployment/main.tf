data "kubernetes_namespace" "wp_namespace" {
  metadata {
    name = "wp-namespace"
  }
}

data "aws_ebs_volume" "wordpress_volume" {
  most_recent = true

  filter {
    name   = "volume-type"
    values = ["gp3"]
  }

  filter {
    name   = "tag:Name"
    values = ["wordpress-volume"]
  }
}

resource "kubernetes_secret" "wordpress_app_secret" {
    metadata {
        name      = "appsecret"
        namespace = "wp-namespace"
        labels = {
      app = "wordpress_app"
    }
    }

    data = {
        secret_key     = "appsecretvalue"
    }
    
}

/*
resource "kubernetes_config_map" "env_values" {
  metadata {
    name = "app-env-values"
      labels = {
      app = "wordpress_app"
    }
  }

  data = {
    WORDPRESS_DB_HOST = "wordpress-mysql",
    WORDPRESS_DB_NAME = "wordpressdb",
    WORDPRESS_DB_USER = "wordpress-db-user",
    wordpress = "wordpress"
  }
}
*/

resource "kubernetes_secret" "wordpress_db_secret" {
    metadata {
        name      = "wordpress-db1"
        namespace = "wp-namespace"
           labels = {
      app = "wordpress_app"
    }
    }

    data = {
        wordpress-db-password  = "dbsecretvalue"
    }
    
}


resource "kubernetes_persistent_volume" "wp_app_persistent_volume" {
  metadata {
    name = "wp-pv-app"
    labels = {
      app = "wordpress_app"
    }
  }
  spec {
    storage_class_name = "wp-storage"
    capacity = {
      storage = "20Gi"
    }
    access_modes = ["ReadWriteOnce"]
        persistent_volume_source {
       # csi {
        #  driver = "ebs.csi.aws.com"
         # volume_handle = "awsElasticBlockStore"
        #}
         aws_elastic_block_store {
           volume_id = data.aws_ebs_volume.wordpress_volume.id

        }
    }

  }
}


resource "kubernetes_persistent_volume_claim" "wp_app_persistent_volume_claim" {
  metadata {
    name = "wp-app-presistentclaim"
    namespace = "wp-namespace"
    labels = {
      app = "wordpress_app"
    }
  }
  spec {
    storage_class_name = "wp-storage"
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
    selector {
      match_labels = {
 
         app = "wordpress_app"
      }  
    }
    volume_name = "${kubernetes_persistent_volume.wp_app_persistent_volume.metadata.0.name}"
  }
}



resource "kubernetes_deployment" "wordpress_app" {
  metadata {
    name      = "wp-app-deployment"
    namespace = data.kubernetes_namespace.wp_namespace.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "wordpress_app"
        tier = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress_app"
          tier = "frontend"
        }
      }
      spec {
        container {
          image = "wordpress:6.2.1-apache"
          name  = "wordpress"
          port {
            container_port = 80
            name = "wordpress-app"
          }
          env {
           name = "WORDPRESS_DB_HOST"
           value = "wordpress-mysql"
            }
          env {
           name = "WORDPRESS_DB_NAME"
           value = "wordpressdb"
            }
           env {
           name = "WORDPRESS_DB_PASSWORD"
           value_from {
              secret_key_ref {
                name = kubernetes_secret.wordpress_db_secret.metadata[0].name
                key = "wordpress-db-password"
              } 
           }
            }
            env {
              name = "WORDPRESS_DB_USER"
              value = "wordpress-db-user"
            }
          volume_mount {
            name = "wordpress-persistent-storage"
            mount_path =  "/var/www/html"
          }

        }
        volume{
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = "wp-app-presistentclaim"
          }
        }


      }
    }
  }
}
resource "kubernetes_service" "wp_app_service" {
  metadata {
    name      = "wp-app-service"
    namespace = data.kubernetes_namespace.wp_namespace.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.wordpress_app.spec.0.template.0.metadata.0.labels.app
      tier = kubernetes_deployment.wordpress_app.spec.0.template.0.metadata.0.labels.tier
    }
    type = "LoadBalancer"
    port {
      port        = 80
      target_port = 80
    }
  }
}