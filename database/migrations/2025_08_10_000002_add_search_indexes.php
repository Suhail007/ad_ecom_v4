<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        // Add index for post_type and post_status combination
        DB::statement('CREATE INDEX IF NOT EXISTS type_status_date ON wp_posts(post_type, post_status, post_date)');
        
        // Add FULLTEXT index for post_title and post_name
        DB::statement('ALTER TABLE wp_posts ADD FULLTEXT INDEX IF NOT EXISTS post_title_name_ft(post_title, post_name)');
        
        // Add index for post_modified
        DB::statement('CREATE INDEX IF NOT EXISTS post_modified_idx ON wp_posts(post_modified)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS type_status_date ON wp_posts');
        DB::statement('DROP INDEX IF EXISTS post_title_name_ft ON wp_posts');
        DB::statement('DROP INDEX IF EXISTS post_modified_idx ON wp_posts');
    }
}; 