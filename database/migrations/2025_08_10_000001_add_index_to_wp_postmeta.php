<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        DB::statement('CREATE INDEX IF NOT EXISTS idx_postmeta_postid_metakey ON wp_postmeta(post_id, meta_key)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS idx_postmeta_postid_metakey ON wp_postmeta');
    }
}; 