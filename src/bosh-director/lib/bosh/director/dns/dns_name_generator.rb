module Bosh::Director
  class DnsNameGenerator
    def self.dns_record_name(hostname, job_name, network_name, deployment_name, root_domain)
      if network_name == '%'
        canonicalized_network_name = '%'
      else
        canonicalized_network_name = Canonicalizer.canonicalize(network_name)
      end

      [ hostname,
        Canonicalizer.canonicalize(job_name),
        canonicalized_network_name,
        Canonicalizer.canonicalize(deployment_name),
        root_domain
      ].join('.')
    end
  end
end