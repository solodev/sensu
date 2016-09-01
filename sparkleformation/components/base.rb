SparkleFormation.build do
  set!('AWSTemplateFormatVersion', '2010-09-09')

  parameters do
    creator do
      type 'String'
      description 'Creator of the stack'
      default ENV['USER']
      disable_apply true
    end

    vpc_id do
      type 'String'
    end

    subnet_ids do
      type 'CommaDelimitedList'
    end
  end
end
