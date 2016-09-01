SparkleFormation.new(:sensu_infra).load(:base).overrides do
  nest!(:elasticache)
  nest!(:sensu)
end
