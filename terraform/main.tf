module "network" {
  source   = "./modules/network"
  app_name = var.app_name
}

module "eks" {
  source            = "./modules/eks"
  app_name          = var.app_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  cluster_version   = var.cluster_version
}

module "portal" {
  source   = "./modules/portal"
  app_name = var.app_name
  region   = var.aws_region
}
