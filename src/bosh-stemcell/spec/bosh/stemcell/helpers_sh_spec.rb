require 'serverspec'
require 'spec_helper'

context 'helpers.sh' do

  context 'add_on_exit runs cleanup commands in LIFO order' do
    describe command(File.expand_path('../../../assets/on_exit_with_normal_completion.sh', __FILE__)) do
      its(:stdout) { should match <<EOF }
end of script
Running 4 on_exit items...
Running cleanup command echo fourth on_exit action (try: 0)
fourth on_exit action
Running cleanup command echo third on_exit action (try: 0)
third on_exit action
Running cleanup command echo second on_exit action (try: 0)
second on_exit action
Running cleanup command echo first on_exit action (try: 0)
first on_exit action
EOF
    end

    describe command(File.expand_path('../../../assets/on_exit_with_error_exit.sh', __FILE__)) do
      its(:stdout) { should match <<EOF }
Running 2 on_exit items...
Running cleanup command echo second on_exit action (try: 0)
second on_exit action
Running cleanup command echo first on_exit action (try: 0)
first on_exit action
EOF
    end
  end

  describe command(File.expand_path('../../../assets/on_exit_with_failing_cleanup_command.sh', __FILE__)) do
    its(:stdout) { should match <<EOF }
end of script
Running 1 on_exit items...
Running cleanup command false (try: 0)
Running cleanup command false (try: 1)
Running cleanup command false (try: 2)
Running cleanup command false (try: 3)
Running cleanup command false (try: 4)
Running cleanup command false (try: 5)
Running cleanup command false (try: 6)
Running cleanup command false (try: 7)
Running cleanup command false (try: 8)
Running cleanup command false (try: 9)
EOF
  end

end
