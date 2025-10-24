<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateAdminUser extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:create-admin-user';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Creates the initial admin user from environment variables if no users exist';

    /**
     * Execute the console command.
     */
    public function handle(): void
    {
        if (User::count() > 0) {
            $this->warn('Admin user already exists. Aborting.');
            return;
        }

        $this->info('Creating initial admin user...');

        User::create([
            'name' => config('admin-user.admin_name'),
            'email' => config('admin-user.admin_email'),
            'password' => Hash::make(config('admin-user.admin_password')),
        ]);

        $this->info('Admin user created successfully!');
    }
}
