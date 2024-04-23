resource "kubernetes_namespace" "wp_namespace" {
  metadata {
    name = "wp-namespace"
  }
}

resource "aws_ebs_volume" "wordpress_volume" {
  availability_zone = "ap-south-1a"  # Specify the availability zone where the EBS volume will exist
  size              = 20            # Size of the volume in GiBs
  type = "gp3"
  tags = {
    Name = "wordpress-volume"  # Optional: Assign tags to the volume
  }
}

resource "kubernetes_storage_class" "wp-storage" {
  metadata {
    name = "wp-storage"
 
    labels = {
       name = "wp-db"
       app = "wordpress_db"
    }
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Delete"
  parameters = {
    type = "gp3"
  }
  volume_binding_mode = "Immediate"
  
}

resource "kubernetes_config_map" "env_values" {
  metadata {
    name = "db-env-values"
    namespace = "wp-namespace"
  }

  data = {
    WORDPRESS_DB_HOST = "wordpress-db-host",
    WORDPRESS_DB_NAME = "wordpressdb",
    WORDPRESS_DB_USER = "wordpress-db-user",
    wordpress = "wordpress"
  }
}

resource "kubernetes_secret" "wordpress_db_secret" {
    metadata {
        name      = "wordpress-db-password"
        namespace = "wp-namespace"
          labels = {
       name = "wp-db"
       app = "wordpress_db"
    }
    }
 
    data = {
        username = "wordpress-db-password"
        wordpress-pwd   = "dbsecretvalue"
    }
       type = "kubernetes.io/basic-auth"
}

resource "kubernetes_persistent_volume" "wp_db_persistent_volume" {
  metadata {
    name = "mysql-pv"
   
    labels = {
       name = "wp-db"
       app = "wordpress_db"
    }
    
  }
  spec {
    storage_class_name = "wp-storage"
    capacity = {
      storage = "20Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      #  csi {
       #   driver = "ebs.csi.aws.com"
        #  volume_handle = "awsElasticBlockStore"
        #}
        aws_elastic_block_store {
           volume_id = aws_ebs_volume.wordpress_volume.id

        }

    }

  }
}


resource "kubernetes_persistent_volume_claim" "wp_db_persistent_volume_claim" {
  metadata {
    name = "wp-db-presistentclaim"
    namespace = "wp-namespace"
    labels = {
       name = "wp-db"
       app = "wordpress_db"
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
         name = "wp-db"
         app = "wordpress_db"
      }  
    }
    volume_name = "${kubernetes_persistent_volume.wp_db_persistent_volume.metadata.0.name}"
  }
}

resource "kubernetes_service" "wp-mysql" {
  metadata {
    name = "wordpress-mysql"
        namespace = "wp-namespace"
    labels = {
       name = "wp-db"
       app = "wordpress_db"
    }
  }
  spec {
    selector = {
      app = "wordpress_db"
    }
    #session_affinity = "ClientIP"
    port {
      port        = 3306
      #target_port = 80
    }

    #type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "wordpress_db" {
  metadata {
    name      = "wp-db-deployment"
    namespace = kubernetes_namespace.wp_namespace.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "wordpress_db"
        tier = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress_db"
          tier = "backend"
        }
      }
      spec {
        container {
          image = "mysql:8.0"
          name  = "mysql"
          port {
            container_port = 3306
            name = "mysql"
          }
                env {
               name = "MYSQL_DATABASE"
              value = "wordpressdb"
            }
          env {
           name = "MYSQL_USER"
           value = "wordpress-db-user"
            }
           env {
           name = "MYSQL_PASSWORD"
           value_from {
              secret_key_ref {
                name = kubernetes_secret.wordpress_db_secret.metadata[0].name
                key = "wordpress-pwd"
              } 
           }
            }

           env {
               name = "WORDPRESS_DB_HOST"
              value = "wordpress-mysql"
            }

          volume_mount {
            name = "wordpress-persistent-storage"
            mount_path =  "/var/lib/mysql"
          }

        }
        volume{
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = "wp-db-presistentclaim"
          }
        }


      }
    }
  }
   depends_on = [kubernetes_persistent_volume_claim.wp_db_persistent_volume_claim]
}
