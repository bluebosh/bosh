require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::CompiledPackagesToDeletePicker do
    subject(:compiled_packages_to_delete_picker) { Jobs::Helpers::CompiledPackagesToDeletePicker }

    describe '.pick' do
      before do
        Models::Stemcell.make(operating_system: 'windows', version: '3.1')
        Models::Stemcell.make(operating_system: 'ubuntu-xenial', version: '97.0', id: 2)
        Models::CompiledPackage.make(stemcell_os: 'windows', stemcell_version: '3.1')
        Models::CompiledPackage.make(stemcell_os: 'windows', stemcell_version: '3.0')
      end

      describe 'when there is a compiled package for a deleted major stemcell version' do
        it 'includes that package' do
          compiled_package_on_old_stemcell = Models::CompiledPackage.make(
            stemcell_os: 'windows',
            stemcell_version: '2.1',
          )
          compiled_package_on_stemcell_being_deleted = Models::CompiledPackage.make(
            stemcell_os: 'ubuntu-xenial',
            stemcell_version: '97.0',
          )
          expect(subject.pick([{ 'operating_system' => 'ubuntu-xenial', 'version' => '97.0', 'id' => 2 }]))
            .to contain_exactly(compiled_package_on_old_stemcell, compiled_package_on_stemcell_being_deleted)
        end
      end
    end
  end
end
